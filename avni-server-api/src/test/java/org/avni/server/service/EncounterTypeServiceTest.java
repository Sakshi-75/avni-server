package org.avni.server.service;

import org.avni.server.dao.EncounterTypeRepository;
import org.avni.server.dao.OperationalEncounterTypeRepository;
import org.avni.server.dao.application.FormMappingRepository;
import org.avni.server.domain.EncounterType;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class EncounterTypeServiceTest {
    @Mock private EncounterTypeRepository encounterTypeRepository;
    @Mock private OperationalEncounterTypeRepository operationalEncounterTypeRepository;
    @Mock private FormMappingRepository formMappingRepository;
    
    private EncounterTypeService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new EncounterTypeService(encounterTypeRepository, 
                                          operationalEncounterTypeRepository, 
                                          formMappingRepository);
    }
    
    @Test
    public void testIsNonScopeEntityChangedTrue() {
        DateTime dateTime = DateTime.now();
        when(encounterTypeRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertTrue(result);
        verify(encounterTypeRepository).existsByLastModifiedDateTimeGreaterThan(dateTime);
    }
    
    @Test
    public void testIsNonScopeEntityChangedFalse() {
        DateTime dateTime = DateTime.now();
        when(encounterTypeRepository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(false);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertFalse(result);
    }
}
