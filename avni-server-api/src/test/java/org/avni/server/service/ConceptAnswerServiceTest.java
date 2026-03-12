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
    public void testIsNonScopeEntityChangedTrue() {
        DateTime dateTime = DateTime.now();
        when(conceptAnswerRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertTrue(result);
        verify(conceptAnswerRepository).existsByLastModifiedDateTimeGreaterThan(dateTime);
    }
    
    @Test
    public void testIsNonScopeEntityChangedFalse() {
        DateTime dateTime = DateTime.now();
        when(conceptAnswerRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(false);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertFalse(result);
        verify(conceptAnswerRepository).existsByLastModifiedDateTimeGreaterThan(dateTime);
    }
    
    @Test
    public void testIsNonScopeEntityChangedWithOldDate() {
        DateTime oldDate = DateTime.now().minusDays(30);
        when(conceptAnswerRepository.existsByLastModifiedDateTimeGreaterThan(oldDate)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(oldDate);
        
        assertTrue(result);
    }
}
