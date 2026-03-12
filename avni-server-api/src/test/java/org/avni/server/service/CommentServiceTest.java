package org.avni.server.service;

import org.avni.server.dao.*;
import org.avni.server.domain.Comment;
import org.avni.server.domain.CommentThread;
import org.avni.server.domain.Individual;
import org.avni.server.web.request.CommentContract;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class CommentServiceTest {
    @Mock private CommentRepository commentRepository;
    @Mock private IndividualRepository individualRepository;
    @Mock private CommentThreadRepository commentThreadRepository;
    @Mock private SubjectTypeRepository subjectTypeRepository;
    @Mock private CommentContract commentContract;
    @Mock private Individual individual;
    @Mock private CommentThread commentThread;
    
    private CommentService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new CommentService(commentRepository, individualRepository, 
                                     commentThreadRepository, subjectTypeRepository);
    }
    
    @Test
    public void testDeleteComment() {
        Comment comment = new Comment();
        when(commentRepository.saveEntity(comment)).thenReturn(comment);
        
        Comment result = service.deleteComment(comment);
        
        assertTrue(result.isVoided());
        verify(commentRepository).saveEntity(comment);
    }
}
