package org.avni.server.service;

import org.avni.server.dao.ConceptAnswerRepository;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ConceptAnswerServiceTest {
    @Mock private ConceptAnswerRepository conceptAnswerRepository;
    private ConceptAnswerService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ConceptAnswerService(conceptAnswerRepository);
    }
    
    @Test
    public void testIsNonScopeEntityChanged() {
        DateTime dateTime = DateTime.now();
        when(conceptAnswerRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(false);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertFalse(result);
        verify(conceptAnswerRepository).existsByLastModifiedDateTimeGreaterThan(dateTime);
    }
}
